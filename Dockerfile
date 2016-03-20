#
# example Dockerfile for https://docs.docker.com/examples/postgresql_service/
# Build: build -t jenkins-plugins-postgre .
# Run: docker run --rm -P --name pg_jenkins-plugins jenkins-plugins-postgre

FROM ubuntu

# Add the PostgreSQL PGP key to verify Debian package.

ADD . /
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key add /ACCC4CF8.asc
RUN apt-get update
RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

# Add PostgreSQL's repository. It contains the most recent stable release
#     of PostgreSQL, ``9.3``.
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Install ``python-software-properties``, ``software-properties-common`` and PostgreSQL 9.3
#  There are some warnings (in red) that show up during the build. You can hide
#  them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y python-software-properties software-properties-common postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3

# Note: The official Debian and Ubuntu images automatically ``apt-get clean``
# after each ``apt-get``

RUN locale-gen sv_SE.UTF-8
RUN pg_dropcluster --stop 9.3 main
RUN pg_createcluster --locale=sv_SE.UTF-8 --start 9.3 main

# Run the rest of the commands as the ``postgres`` user created by the ``postgres-9.3`` package when it was ``apt-get installed``
USER postgres

# Create a PostgreSQL role named ``jenkinsplugins`` with ``jenkinsplugins`` as the password and
# then create a database `jenkinsplugins` owned by the ``jenkinsplugins`` role.
# Note: here we use ``&&\`` to run commands one after the other - the ``\``
#       allows the RUN command to span multiple lines.
RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE USER jenkinsplugins WITH SUPERUSER PASSWORD 'jenkinsplugins';" &&\
    createdb -E 'UTF8' -O jenkinsplugins jenkinsplugins &&\
    psql --command "CREATE ROLE jenkinsplugins_anv WITH LOGIN PASSWORD 'jenkinsplugins_anv' NOSUPERUSER;"

RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE SCHEMA IF NOT EXISTS application AUTHORIZATION jenkinsplugins_anv;" &&\
    psql --command "CREATE TABLE application.category (id serial primary key, category varying(255) UNIQUE NOT NULL, createdAt NOT NULL DEFAULT now()::date);" &&\
    psql --command "CREATE TABLE application.plugin (id serial primary key, name character varying(255) UNIQUE NOT NULL, updatedAt timestamp without time zone NOT NULL);" &&\
    psql --command "CREATE TABLE application.category_plugin(category_id int REFERENCES category (id) ON UPDATE CASCADE, plugin_id int REFERENCES plugin (id) ON UPDATE CASCADE ON DELETE CASCADE, CONSTRAINT category_plugin PRIMARY KEY (category_id, plugin_id));"

RUN /etc/init.d/postgresql start &&\
    psql --command "GRANT SELECT, INSERT, DELETE ON TABLE application.category TO jenkinsplugins_anv;"  &&\
    psql --command "GRANT SELECT, INSERT, DELETE ON TABLE application.plugin TO jenkinsplugins_anv;"  &&\
    psql --command "GRANT SELECT, INSERT, DELETE ON TABLE application.category_plugin TO jenkinsplugins_anv;" &&\
    psql --command "GRANT USAGE, SELECT, INSERT, DELETE ON ALL SEQUENCES IN SCHEMA application to jenkinsplugins_anv;"



# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.3/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

# Set the default command to run when starting the container
CMD ["/usr/lib/postgresql/9.3/bin/postgres", "-D", "/var/lib/postgresql/9.3/main", "-c", "config_file=/etc/postgresql/9.3/main/postgresql.conf"]
