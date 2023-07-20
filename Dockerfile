FROM node:lts AS cli-build

RUN mkdir -p /athenapdf/build/artifacts/
WORKDIR /athenapdf/

COPY cli/package.json /athenapdf/
RUN npm install

COPY cli/package.json /athenapdf/build/artifacts/
RUN cp -r /athenapdf/node_modules/ /athenapdf/build/artifacts/

COPY cli/src /athenapdf/build/artifacts/
RUN npm run build:linux

FROM debian:latest AS cli
RUN echo 'deb http://httpredir.debian.org/debian/ stable main contrib non-free' >> /etc/apt/sources.list

RUN apt-get -yq update && \
    apt-get -yq install \
        wget \
        xvfb \
        libasound2 \
        libgconf-2-4 \
        libgtk2.0-0 \
        libnotify4 \
        libnss3 \
        libxss1 \
        culmus \
        fonts-beng \
        fonts-dejavu \
        fonts-hosny-amiri \
        fonts-lklug-sinhala \
        fonts-lohit-guru \
        fonts-lohit-knda \
        fonts-samyak-gujr \
        fonts-samyak-mlym \
        fonts-samyak-taml \
        fonts-sarai \
        fonts-sil-abyssinica \
        fonts-sil-padauk \
        fonts-telu \
        fonts-thai-tlwg \
        ttf-wqy-zenhei \
    && apt-get -yq autoremove \
    && apt-get -yq clean \
    && rm -rf /var/lib/apt/lists/* \
    && truncate -s 0 /var/log/*log

COPY cli/fonts.conf /etc/fonts/conf.d/100-athena.conf

COPY --from=cli-build /athenapdf/build/athenapdf-linux-x64/ /athenapdf/
WORKDIR /athenapdf/

ENV PATH /athenapdf/:$PATH

COPY cli/entrypoint.sh /athenapdf/entrypoint.sh

RUN mkdir -p /converted/
WORKDIR /converted/

CMD ["athenapdf"]

ENTRYPOINT ["/athenapdf/entrypoint.sh"]


	# @docker cp `docker ps -q -n=1`:$(CLI_DOCKER_ARTIFACT_DIR) $(CLI_DIR)/build/
	# @docker rm -f `docker ps -q -n=1`
	# @docker build --rm -t $(CLI_IMAGE) -f $(CLI_DIR)/Dockerfile $(CLI_DIR)/
	# @rm -rf $(CLI_DIR)/build/
    
FROM golang:1.10-alpine AS weaver-build
WORKDIR /go/src/github.com/arachnys/athenapdf/weaver

RUN apk add --update git
RUN go get -u github.com/golang/dep/cmd/dep

COPY weaver/Gopkg.lock weaver/Gopkg.toml ./
RUN dep ensure --vendor-only -v

COPY weaver/ ./

RUN \
  CGO_ENABLED=0 go build -v -o weaver .


	# @docker run -t $(SERVICE_IMAGE)-build /bin/true
	# @docker cp `docker ps -q -n=1`:$(SERVICE_DOCKER_ARTIFACT_FILE) $(SERVICE_DIR)/build/
	# @docker rm -f `docker ps -q -n=1`
	# @chmod +x $(SERVICE_DIR)/build/weaver
	# @docker build --rm -t $(SERVICE_IMAGE) -f $(SERVICE_DIR)/Dockerfile $(SERVICE_DIR)/
	# @rm -rf $(SERVICE_DIR)/build/

FROM cli AS weaver-service

ENV GIN_MODE release

RUN \
  wget https://github.com/Yelp/dumb-init/releases/download/v1.0.0/dumb-init_1.0.0_amd64.deb \
  && dpkg -i dumb-init_*.deb \
  && rm dumb-init_*.deb \
  && mkdir -p /athenapdf-service/tmp/

COPY --from=weaver-build /go/src/github.com/arachnys/athenapdf/weaver/weaver /athenapdf-service/
WORKDIR /athenapdf-service/

ENV PATH /athenapdf-service/:$PATH

COPY weaver/conf/ /athenapdf-service/conf/

EXPOSE 8080

CMD ["dumb-init", "weaver"]
ENTRYPOINT ["/athenapdf-service/conf/entrypoint.sh"]