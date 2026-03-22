ARG LINKDING_IMAGE_TAG=latest

FROM docker.io/sissbruecker/linkding:$LINKDING_IMAGE_TAG

# Copy custom uwsgi. This allows to run with 256MB RAM.
COPY uwsgi.ini /etc/linkding/uwsgi.ini

CMD ["/etc/linkding/bootstrap.sh"]
