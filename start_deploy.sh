#!/usr/bin/sh
version=1.0.5

cd aws-beanstalk-tunkki
gem build aws_beanstalk_tunkki.gemspec
gem install ./aws_beanstalk_tunkki-$version.gem
aws_beanstalk_tunkki --app $1 --branch $2 --dir $3 --region $4 --hosts ${5:-false} --local ${6:-false} \
    --update-template ${7:-false}
