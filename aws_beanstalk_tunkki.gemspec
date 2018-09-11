Gem::Specification.new do |s|
  s.name        = 'aws_beanstalk_tunkki'
  s.version     = '1.0.0'
  s.executables << 'aws_beanstalk_tunkki'
  s.date        = '2018-09-11'
  s.summary     = "AWS Beanstalk Tunkki"
  s.description = "Tool for deploying your app to AWS ElasticBeanstalk."
  s.authors     = ["Valtteri Pajunen", "Janne Saraste"]
  s.email       = 'IL.Tekniikka@iltalehti.fi'
  s.files       = ["lib/aws_beanstalk_tunkki.rb"]
  s.homepage    = 'https://github.com/almamedia/aws-beanstalk-tunkki'
  s.licenses    = ['MIT']
  s.add_runtime_dependency 'aws-sdk-elasticbeanstalk', '~> 1.11', '>= 1.11'
  s.add_runtime_dependency 'aws-sdk-s3', '~> 1.19', '>= 1.19'
end
