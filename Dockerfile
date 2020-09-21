FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y \
    && apt-get dist-upgrade -y \
    && apt-get install -y apache2 apache2-utils wget emacs-nox htop less dcmtk \
    && apt-get clean


CMD ["apache2ctl", "-D", "FOREGROUND"]
EXPOSE 3000
