# Stage 1: Build environment
ARG WORKER_CUDA_VERSION=12.1.0
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION} AS build-env

# Set working directory
WORKDIR /app

# Instal dependensi yang diperlukan
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Instal Miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh && \
    /bin/bash /miniconda.sh -b -p /opt/miniconda && \
    rm /miniconda.sh

# Tambahkan Miniconda ke PATH
ENV PATH="/opt/miniconda/bin:$PATH"

# Buat environment Conda
RUN conda create -n sparktts python=3.12 -y

# Aktifkan environment dan instal Torch yang sesuai dengan CUDA
RUN /bin/bash -c "conda activate sparktts && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"

# Ensure Conda environment is active for the following commands
SHELL ["/bin/bash", "-c"]

# Copy requirements dan instal
COPY requirements.txt /app/requirements.txt
RUN conda activate sparktts && \
    pip install --upgrade pip && \
    pip install -r /app/requirements.txt --no-cache-dir && \
    rm /app/requirements.txt

# Stage 2: Final image
FROM runpod/base:0.6.2-cuda${WORKER_CUDA_VERSION}
WORKDIR /app

# Copy Conda environment dan project files dari build stage
COPY --from=build-env /opt/miniconda /opt/miniconda
COPY . .

# Aktifkan Conda environment untuk eksekusi final
ENV PATH="/opt/miniconda/bin:$PATH"
CMD ["python3.12", "-u", "/app/handler.py"]