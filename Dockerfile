# Base image with specified CUDA version
ARG WORKER_CUDA_VERSION=12.1.0
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION}

# Reinitialize the ARG as it's lost after FROM
ARG WORKER_CUDA_VERSION=12.1.0

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

# Initialize Conda and create environment
RUN /opt/miniconda/bin/conda init bash && \
    /opt/miniconda/bin/conda create -n sparktts -y python=3.12 && \
    echo "source /opt/miniconda/bin/activate sparktts" >> ~/.bashrc

# Ensure subsequent commands use the activated Conda environment
SHELL ["/bin/bash", "-c"]

# Copy requirements.txt into the container
COPY requirements.txt /app/requirements.txt

# Install Python dependencies in Conda environment
RUN source /opt/miniconda/bin/activate sparktts && \
    pip install --upgrade pip --no-cache-dir && \
    pip install -r /app/requirements.txt --no-cache-dir && \
    conda clean --all --yes && \
    rm /app/requirements.txt /tmp/*

# Install Torch with proper CUDA version
RUN source /opt/miniconda/bin/activate sparktts && \
    CUDA_VERSION_SHORT=$(echo ${WORKER_CUDA_VERSION} | cut -d. -f1,2 | tr -d .) && \
    pip uninstall torch -y && \
    pip install --pre torch==2.6.0.dev20241112+cu${CUDA_VERSION_SHORT} \
    --index-url https://download.pytorch.org/whl/nightly/cu${CUDA_VERSION_SHORT} --no-cache-dir && \
    conda clean --all --yes && \
    rm -rf /tmp/* /opt/miniconda/pkgs/*

# Set HF_HOME to handle HuggingFace cache
ENV HF_HOME=/runpod-volume

# Copy project files into the container
COPY . .

# Debugging: Check disk usage during build
RUN df -h && du -sh /tmp /opt/miniconda/envs/sparktts

# Set the entry point to the handler script
CMD ["python3.12", "-u", "/app/handler.py"]