#### Postgres installation using docker.
  see tutorial: https://docs.docker.com/examples/postgresql_service/
  docker build -t jenkins-plugins-postgre .
  or get directly using: docker build -t="dockerfile/jenkins-plugins-postgre" github.com/skiarn/jenkins-plugins-postgre
  
  run in foreground.
  docker run --rm -P --name pg_jenkins-plugins jenkins-plugins-postgre

  find port:
  docker ps
  ex: port 192.168.59.103:32768
