# Stage 1: Build environment
ARG WORKER_CUDA_VERSION=12.1.0
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION} AS build-env

# Set working directory
WORKDIR /app

# Use Bash as default shell
SHELL ["/bin/bash", "--login", "-c"]

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh && \
    /bin/bash /miniconda.sh -b -p /opt/miniconda && \
    rm /miniconda.sh

# Add Miniconda to PATH
ENV PATH="/opt/miniconda/bin:$PATH"

# Initialize Conda for bash shell
RUN conda init bash

# Create and configure Conda environment
RUN conda create -n sparktts python=3.12 -y && \
    echo "conda activate sparktts" >> ~/.bashrc

# Activate Conda environment and install PyTorch + CUDA
RUN /bin/bash -c "source ~/.bashrc && conda activate sparktts && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"

# Copy Python requirements and install
COPY requirements.txt /app/requirements.txt
RUN /bin/bash -c "source ~/.bashrc && conda activate sparktts && \
    pip install --upgrade pip && \
    pip install -r /app/requirements.txt --no-cache-dir"

# Clone Spark-TTS model using Git LFS
RUN mkdir -p pretrained_models && \
    git lfs install && \
    git clone https://huggingface.co/SparkAudio/Spark-TTS-0.5B pretrained_models/Spark-TTS-0.5B

# Stage 2: Final image
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION}
WORKDIR /app

# Use Bash as default shell
SHELL ["/bin/bash", "--login", "-c"]

# Copy Conda environment and project files from build stage
COPY --from=build-env /opt/miniconda /opt/miniconda
COPY --from=build-env /app /app

# Add Miniconda to PATH
ENV PATH="/opt/miniconda/bin:$PATH"

# Activate Conda environment for final execution
CMD ["bash", "-c", "source ~/.bashrc && conda activate sparktts && python -u /app/handler.py"]
