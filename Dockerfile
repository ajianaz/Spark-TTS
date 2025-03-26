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
    /opt/miniconda/bin/conda clean -tipsy && \
    ln -s /opt/miniconda/bin/conda /usr/bin/conda && \
    apt-get clean

# Initialize Conda and create environment
RUN conda create -n sparktts -y python=3.12 && \
    echo "conda activate sparktts" > ~/.bashrc

# Activate conda environment for all future RUN commands
SHELL ["/bin/bash", "-c", "conda activate sparktts && conda config --set always_yes yes --set changeps1 no && source ~/.bashrc && conda activate sparktts &&"]

# Copy requirements and install Python dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && \
    pip install -r /app/requirements.txt --no-cache-dir && \
    rm /app/requirements.txt

# Uninstall torch and install the appropriate version
RUN pip uninstall torch -y && \
    CUDA_VERSION_SHORT=$(echo ${WORKER_CUDA_VERSION} | cut -d. -f1,2 | tr -d .) && \
    pip install --pre torch==2.4.0.dev20240518+cu${CUDA_VERSION_SHORT} --index-url https://download.pytorch.org/whl/nightly/cu${CUDA_VERSION_SHORT} --no-cache-dir

# Set HF_HOME to handle HuggingFace cache
ENV HF_HOME=/runpod-volume

# Copy project files into the container
COPY . .

# Set the entry point to the handler script
CMD ["python3.11", "-u", "/app/handler.py"]
