# AWS Beanstalk Tunkki

AWS Beanstalk Tunkki is a small and relatively generic AWS Beanstalk deployment helper which essentially performs the same tasks as AWS & EB CLI tools.

*Note: This tool is released as MIT licensed open source software.*

### Additional notes
This tool makes the assumption that development and production environments are separated into different AWS accounts. However it can also be used with single account deployments.

In order to create AWS resources (eg. deploy to beanstalk), this tool requires AWS access key and secret to be included in .travis.yml file with appropriate key names. (See usage below)

In order to perform beanstalk deployment, an S3 bucket is required for storing application version ZIP files.
This tool makes the assumption that there is a S3 bucket named in the following manner:
```
elasticbeanstalk-eu-west-1-*
eg. elasticbeanstalk-eu-west-1-123456789
eg. elasticbeanstalk-[region]-[account_number]
```

### Usage from local machine
Make sure to authenticate via aws-mfa and set `export AWS_PROFILE=my-dev-profile` environment variable first.
```
user@localhost:~$ gem install aws_beanstalk_tunkki
user@localhost:~$ aws_beanstalk_tunkki --app "myapp" --branch "dev" --dir "/home/user/myapp" --region "eu-west-1" --hosts "false" --local "true"
```


### Usage
1. Encrypt appropriate IAM user access keys with travis encrypt:
```
travis encrypt AWS_ACCESS_KEY_ID_PROD=ABCDEFGH123456 --add
travis encrypt AWS_SECRET_ACCESS_KEY_PROD=ABCDEFGH123456 --add
travis encrypt AWS_ACCESS_KEY_ID_DEV=ABCDEFGH123456 --add
travis encrypt AWS_SECRET_ACCESS_KEY_DEV=ABCDEFGH123456 --add
```
2. Add the following to `.travis.yml`:
```
before_deploy:
- git clone https://github.com/almamedia/aws-beanstalk-tunkki.git
```
```
deploy:
- provider: script
  script: sh ./aws-beanstalk-tunkki/start_deploy.sh "$app" "$TRAVIS_BRANCH" "$TRAVIS_BUILD_DIR"
    "$AWS_DEFAULT_REGION"
```

or something similar to this

```
before_deploy:
- git clone https://github.com/almamedia/aws-beanstalk-tunkki.git
- |
  HOSTS="false"
  if [[ "${TRAVIS_BRANCH}" == "ft"* ]]; then
    REPO_NAME="${TRAVIS_REPO_SLUG#*/}"
    HOSTS="${REPO_NAME}-${TRAVIS_BRANCH}.ft.il.fi"
  fi
```
```
deploy:
- provider: script
  script: sh ./aws-beanstalk-tunkki/start_deploy.sh "$app" "$TRAVIS_BRANCH" "$TRAVIS_BUILD_DIR"
    "$AWS_DEFAULT_REGION" "$HOSTS"
```

### Example .travis.yml
```
language: ruby
env:
  global:
  - app: my-cool-application
  - platform: Ruby
  - AWS_DEFAULT_REGION: eu-west-1
  - secure: (AWS_ACCESS_KEY_ID_DEV=ABCDEFGH123456)
  - secure: (AWS_SECRET_ACCESS_KEY_DEV=ABCDEFGH123456)
branches:
  only:
  - "/^ft/"
  - "/^dev/"
  - "/^st/"
  - "/^prod/"
script: true
before_deploy:
  - git clone https://github.com/almamedia/aws-beanstalk-tunkki.git
deploy:
  - provider: script
    script: sh ./aws-beanstalk-tunkki/start_deploy.sh "$app" "$TRAVIS_BRANCH" "$TRAVIS_BUILD_DIR" "$AWS_DEFAULT_REGION"
    on:
      all_branches: true
      condition: "! $(git describe --all --exact-match) =~ ^heads/*"
```
