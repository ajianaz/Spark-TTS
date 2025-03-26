# Stage 1: Build environment
ARG WORKER_CUDA_VERSION=12.1.0
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION} AS build-env

# Set working directory
WORKDIR /app

# Install Miniconda
RUN apt-get update && \
    apt-get install -y wget bzip2 && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/miniconda && \
    rm /tmp/miniconda.sh && \
    /opt/miniconda/bin/conda clean --all --yes && \
    ln -s /opt/miniconda/bin/conda /usr/bin/conda && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a Conda environment and install dependencies
RUN /opt/miniconda/bin/conda init bash && \
    /opt/miniconda/bin/conda create -n sparktts -y python=3.12 && \
    echo "source /opt/miniconda/bin/activate sparktts" >> ~/.bashrc

# Ensure Conda environment is active for the following commands
SHELL ["/bin/bash", "-c"]

# Copy requirements and install them
COPY requirements.txt /app/requirements.txt
RUN source /opt/miniconda/bin/activate sparktts && \
    pip install --upgrade pip && \
    pip install -r /app/requirements.txt --no-cache-dir && \
    rm /app/requirements.txt

# Uninstall existing Torch and install the appropriate version
RUN source /opt/miniconda/bin/activate sparktts && \
    CUDA_VERSION_SHORT=$(echo ${WORKER_CUDA_VERSION} | cut -d. -f1,2 | tr -d .) && \
    pip uninstall torch -y && \
    pip install --pre torch==2.6.0.dev20241112+cu${CUDA_VERSION_SHORT} --index-url https://download.pytorch.org/whl/nightly/cu${CUDA_VERSION_SHORT} --no-cache-dir

# Stage 2: Final image
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION}
WORKDIR /app

# Copy Conda environment and project files from build stage
COPY --from=build-env /opt/miniconda /opt/miniconda
COPY . .

# Activate Conda environment for final execution
ENV PATH="/opt/miniconda/bin:$PATH"
CMD ["python3.12", "-u", "/app/handler.py"]