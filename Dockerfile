# Use Amazon Linux 2 as the base to better match Lambda environment for builds
FROM amazonlinux:2

# Install build tools, Python 3 and dependencies required to build libzbar and Python packages
RUN yum -y update && \
    yum -y install python3 python3-devel python3-pip gcc gcc-c++ make automake autoconf libtool git wget \
        libjpeg-devel libpng-devel zlib-devel freetype-devel gettext gettext-devel pkgconfig \
        libX11 libXext libXrender libxcb mesa-libGL libSM libICE && \
    yum clean all

# Install EPEL and try to install zbar from packages; fall back to building from source if needed
RUN set -ex && \
    yum -y install epel-release || true && \
    if yum -y install zbar zbar-devel; then \
        echo "installed zbar from repo"; \
    else \
        echo "repo install failed, building zbar from source"; \
        cd /tmp && \
        wget -q https://github.com/mchehab/zbar/releases/download/0.23.1/zbar-0.23.1.tar.bz2 || true && \
        if [ -f zbar-0.23.1.tar.bz2 ]; then \
            tar xjf zbar-0.23.1.tar.bz2 && cd zbar-0.23.1 && ./configure --without-gtk --without-x && make -j"$(nproc)" && make install && ldconfig && rm -rf /tmp/zbar*; \
        else \
            cd /tmp && git clone --depth 1 https://github.com/mchehab/zbar.git && cd zbar && autoreconf -fi && ./configure --without-gtk --without-x && make -j"$(nproc)" && make install && ldconfig && rm -rf /tmp/zbar; \
        fi; \
    fi

# Make sure the loader will find /usr/local/lib installed libraries
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && ldconfig

# Ensure pip points to python3 pip and upgrade
RUN python3 -m pip install --upgrade pip

# Copy and install Python dependencies
COPY requirements.txt /var/task/requirements.txt
RUN python3 -m pip install -r /var/task/requirements.txt

# Copy application code
COPY . /var/task
WORKDIR /var/task

# Install AWS Lambda Runtime Interface Emulator (RIE) for local testing
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie
RUN chmod +x /usr/local/bin/aws-lambda-rie

# Expose a port for the local test server / RIC
EXPOSE 8080

# Default entrypoint uses the RIE to run awslambdaric so the container can be tested locally
# Container will listen on port 8080 inside; map to host 9000 to test locally:
# docker run -p 9000:8080 <image>
# invoke with:
# curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"image":"<base64>"}'
ENTRYPOINT ["/usr/local/bin/aws-lambda-rie", "python3", "-m", "awslambdaric"]
CMD ["lambda_function.lambda_handler"]

# Notes: if you want to run the Flask test server instead, override the entrypoint:
# docker run --rm -p 8080:8080 --entrypoint python3 <image> server.py
