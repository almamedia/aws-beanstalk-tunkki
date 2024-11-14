require 'aws-sdk-elasticbeanstalk'
require 'aws-sdk-s3'
require 'optparse'
require 'fileutils'

class AWSBeanstalkTunkki

  def initialize
    init_deploy_variables()
  end

  def run_deployment
    application = get_bs_app()
    if !check_bs_env()
      create_bs_env(application.configuration_templates)
    end
    deploy_app(application, generate_version_label())
  end

  def init_deploy_variables
    parse_command_line_options()
    set_application_environment()
    set_aws_clients()
  end

  def parse_command_line_options
    OptionParser.new do |opt|
      opt.on('--app APP_NAME') { |app_name| @app = app_name }
      opt.on('--branch BRANCH_NAME') { |branch_name| @branch = branch_name }
      opt.on('--dir DIR') { |dir| @dir = dir }
      opt.on('--region REGION') { |aws_region| @aws_region = aws_region }
      opt.on('--hosts HOSTS') { |hosts| @hosts = hosts }
      opt.on('--local LOCAL') { |local| @local = local }
      opt.on('--update-template UPDATE_TEMPLATE') { |update_template| @update_template = update_template }
    end.parse!
    raise "Beanstalk application (--app) required!" if @app.nil?
    raise "Git branch (--branch) required!" if @branch.nil?
    raise "App dir location (--dir) required!" if @branch.nil?
    raise "AWS Region missing (--region) required!" if @aws_region.nil?
  end

  def set_application_environment
    case @branch
    when /\Aprod/
      set_application_environment_vars(environment: 'prod', env_simple: 'production')
    when /\Ast/
      set_application_environment_vars(environment: 'st', env_simple: 'staging')
    when /\Adev/
      set_application_environment_vars(environment: 'dev', env_simple: 'development')
    when /\Aft/
      set_application_environment_vars(environment: 'ft', env_simple: 'feature')
    when /\Asb/
      set_application_environment_vars(environment: 'sb', env_simple: 'sandbox')
    else
      raise "Invalid deployment branch name detected! Branch name must start with prod, st, dev, ft or sb"
    end
  end

  def set_application_environment_vars(environment: 'dev', env_simple: '')
    puts "Using branch '#{@branch}' as #{env_simple}"
    @bs_env = @branch.gsub(/[\/:;.,+_<>#]/, '-')
    @environment = environment
    @bs_env_simple = env_simple
  end

  def set_aws_clients
    if @local == "true"
      # Deploy from either local machine or Github Actions.
      # On local machine it requires AWS_PROFILE environment variable to be set
      # and aws-mfa based login before execution.
      @elasticbeanstalk = Aws::ElasticBeanstalk::Client.new(region: @aws_region)
      @s3 = Aws::S3::Client.new(region: @aws_region)
    else
      aws_access_key_id, aws_secret_access_key = *get_aws_keys()
      raise "AWS keys are not defined!" if aws_access_key_id.nil? || aws_secret_access_key.nil?
      credentials = Aws::Credentials.new(aws_access_key_id, aws_secret_access_key)
      @elasticbeanstalk = Aws::ElasticBeanstalk::Client.new(region: @aws_region, credentials: credentials)
      @s3 = Aws::S3::Client.new(region: @aws_region, credentials: credentials)
    end
    bucket = @s3.list_buckets.buckets.find { |b| /\Aelasticbeanstalk-#{@aws_region}/ =~ b.name }
    raise "Could not resolve s3 bucket name." if bucket.nil?
    @s3_bucket_name = bucket.name
  end

  def get_aws_keys
    case @environment
    when 'prod', 'st'
      [ENV['AWS_ACCESS_KEY_ID_PROD'], ENV['AWS_SECRET_ACCESS_KEY_PROD']]
    when 'dev', 'ft'
      [ENV['AWS_ACCESS_KEY_ID_DEV'], ENV['AWS_SECRET_ACCESS_KEY_DEV']]
    when 'sb'
      [ENV['AWS_ACCESS_KEY_ID_SB'], ENV['AWS_SECRET_ACCESS_KEY_SB']]
    end
  end

  def get_bs_app
    application_description = @elasticbeanstalk.describe_applications({application_names: [@app]})
    raise "Application '#{@app}' not found." if application_description.applications.empty?
    application_description.applications.first
  end

  def check_bs_env
    env_name = "#{@app}-#{@bs_env}"
    puts "Checking if Beanstalk environment '#{env_name}' in application '#{@app}' exists."
    application_environments = @elasticbeanstalk.describe_environments({environment_names: [env_name]})
    if is_environment_found?(application_environments.environments)
      puts "Environment '#{env_name}' already exists in application '#{@app}'."
      true
    else
      puts "Environment '#{env_name}' does not exist."
      false
    end
  end

  def is_environment_found?(environments)
    !environments.empty? && !environments.all? { |env| env.status == 'Terminated' }
  end

  def create_bs_env(configuration_templates)
    puts "Searching for Beanstalk configuration template.."

    app_bs_env_simple = "#{@app}-#{@bs_env_simple}"
    app_default       = "#{@app}-default"
    app_bs_env        = "#{@app}-#{@bs_env}"

    conf_template = find_configuration_template(configuration_templates)
    puts "Using '#{conf_template}' configuration template."
    puts "Launching new environment '#{@app}-#{@bs_env}' to application '#{@app}'."

    begin
      if @hosts.nil? || @hosts == "false"
        puts "No added HostHeaders."
        @elasticbeanstalk.create_environment(
          {
            application_name: @app,
            environment_name: app_bs_env,
            cname_prefix:     app_bs_env,
            template_name:    conf_template,
          })
      else
        puts "Add HostHeaders using '#{@hosts}'."
        @elasticbeanstalk.create_environment(
          {
            application_name: @app,
            environment_name: app_bs_env,
            cname_prefix:     app_bs_env,
            template_name:    conf_template,
            option_settings: [
              {
                resource_name: "elbv2",
                namespace: "aws:elbv2:listenerrule:sharedalb",
                option_name: "HostHeaders",
                value: @hosts,
              },
            ],
          })
      end

      if (poll_for_environment_changes(app_bs_env) { |env| env.status != 'Launching' })
        puts "Created environment '#{app_bs_env}'!"
      else
        raise "Timeout when creating environment."
      end
    rescue => e
      raise "Environment launch failed, unable to proceed. Error: #{e}"
    end
  end

  def find_configuration_template(configuration_templates)
    configuration_templates.find do |tpl|
      /(?<conf_app_stub>[\w-]+)-(?<conf_env_stub>\w+)-\w+\z/ =~ tpl
      conf_app_stub && conf_env_stub && @app.match(conf_app_stub) && @bs_env_simple.start_with?(conf_env_stub.slice(0, @bs_env_simple.size))
    end or raise "No configuration templates found, can't create environment."
  end

  def poll_for_environment_changes(env_name)
    print "Making changes to environment #{env_name}"
    thirty_minutes = 12 * 30
    thirty_minutes.times do |i|
      if (yield(@elasticbeanstalk.describe_environments({environment_names: [env_name]}).environments.first))
        print "\n"
        return true
      else
        print '.'
        sleep(5)
      end
    end
    false
  end

  def create_app_version
    version_label = generate_version_label()
    response = @elasticbeanstalk.create_application_version(
      {
        application_name: @app,
        version_label: version_label,
      })
    version_label
  rescue => e
    raise "Application version launch failed. Error: #{e}"
  end

  def deploy_app(app, version_label)
    puts "Deploying application to Beanstalk environment."
    s3_upload_details = upload_version_to_s3(version_label)
    create_app_version(version_label, s3_upload_details)
    update_environment(app, version_label)
  end

  def upload_version_to_s3(version_label)
    zip_name = make_zip_file(version_label)
    zip_name_with_path = "#{@app}/#{zip_name}"
    print "Uploading '#{zip_name}' to S3 bucket (#{@s3_bucket_name})... "
    begin
      File.open(zip_name) do |zip_file|
        @s3.put_object(bucket: @s3_bucket_name, body: zip_file, key: zip_name_with_path)
      end
      print "Done!\n"
      {bucket: @s3_bucket_name, file: zip_name_with_path}
    rescue => e
      raise "Upload to S3 bucket (#{@s3_bucket_name}) failed. Error: #{e}"
    end
  end

  def make_zip_file(version_label)
    print 'Zipping application files ... '
    zip_name = "#{version_label}.zip"
    `cd #{@dir}; zip #{zip_name} -r ./ -x *.git* *.log*`
    raise "Creating ZIP failed!" if $?.exitstatus != 0
    FileUtils.mv("#{@dir}/#{zip_name}", './')
    file_size = (File.size("./#{zip_name}").to_f / 2**20).round(2)
    print "ZIP file size is: #{file_size} MB "
    print "Done!\n"
    zip_name
  end

  def create_app_version(version_label, s3_upload_details)
    if @app.length > 199
      raise "Error! Beanstalk environment name max length is 200 characters! Length: #{@app.length} characters"
    end
    @elasticbeanstalk.create_application_version(
      {
        application_name: @app,
        version_label: version_label,
        source_bundle: {
          s3_bucket: s3_upload_details[:bucket],
          s3_key:    s3_upload_details[:file],
        },
        auto_create_application: true,
        process: true,
      })
    puts "Created application version '#{version_label}'"
  rescue => e
    raise "Creating application version '#{version_label}' failed. Error: #{e}"
  end

  def update_environment(application, version_label)
    sleep(5) # Environment is in an invalid state for this operation. Must be Ready. (RuntimeError)

    parameters = {
      environment_name: "#{@app}-#{@bs_env}",
      version_label: version_label,
      option_settings: [
        {
          namespace: "aws:elasticbeanstalk:command",
          option_name: "Timeout",
          value: "1800",
        }
      ]
    }

    if @update_template == "true"
      conf_template = find_configuration_template(application.configuration_templates)
      puts "Using '#{conf_template}' configuration template."
      parameters[:template_name] = conf_template
    end

    @elasticbeanstalk.update_environment(parameters)
    if (poll_for_environment_changes("#{@app}-#{@bs_env}") { |env| env.status != 'Updating' })
      puts "Updated '#{@app}-#{@bs_env}' environment successfully."
    else
      raise "Timeout of 10 minutes reached when updating environment."
    end
  rescue => e
    raise "Updating environment failed. Error: #{e}"
  end

  def generate_version_label
    time = Time.now
    "#{@app}-#{@bs_env_simple}-#{time.strftime('%Y-%m-%d-%H%M%S')}"
  end

end
