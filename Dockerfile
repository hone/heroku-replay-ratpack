FROM jruby:9.0.5.0

RUN apt-get update && apt-get install -y git-all \
  redis-tools

RUN mkdir -p /app && useradd -d /home heroku

ENV BUNDLE_PATH "vendor/bundle"

USER heroku
ENV HOME /app
WORKDIR /app
ADD init.sh /tmp/
ENTRYPOINT ["bash", "/tmp/init.sh"]
