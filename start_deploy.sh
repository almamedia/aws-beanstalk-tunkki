#!/usr/bin/sh
version=1.0.0

cd aws-beanstalk-tunkki
gem build aws_beanstalk_tunkki.gemspec
gem install ./aws_beanstalk_tunkki-$version.gem
aws_beanstalk_tunkki --app $1 --branch $2 --dir $3 --region $4
