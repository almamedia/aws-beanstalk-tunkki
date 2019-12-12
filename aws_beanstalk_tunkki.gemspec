Gem::Specification.new do |s|
  s.name        = 'aws_beanstalk_tunkki'
  s.version     = '1.0.1'
  s.executables << 'aws_beanstalk_tunkki'
  s.date        = '2019-12-12'
  s.summary     = "AWS Beanstalk Tunkki"
  s.description = "Tool for deploying your app to AWS ElasticBeanstalk."
  s.authors     = ["Valtteri Pajunen", "Janne Saraste"]
  s.email       = 'IL.Tekniikka@iltalehti.fi'
  s.files       = ["lib/aws_beanstalk_tunkki.rb"]
  s.homepage    = 'https://github.com/almamedia/aws-beanstalk-tunkki'
  s.licenses    = ['MIT']
  s.add_runtime_dependency 'aws-sdk-elasticbeanstalk', '~> 1.26', '>= 1.26'
  s.add_runtime_dependency 'aws-sdk-s3', '~> 1.59', '>= 1.59'
end
