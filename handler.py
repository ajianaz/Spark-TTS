import os
import runpod
import boto3
from botocore.exceptions import NoCredentialsError
from io import BytesIO
from datetime import datetime
from cli.inferance import parse_args, run_tts  # Import from cli.inferance


class S3Uploader:
    """Handle S3 uploads, including MinIO."""

    def __init__(self, endpoint, access_key, secret_key, bucket_name, is_parse_path):
        self.client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
        )
        self.bucket_name = bucket_name
        self.is_parse_path = is_parse_path

    def upload_audio(self, filename: str, audio_buffer: BytesIO) -> str:
        """
        Upload audio buffer to S3 or MinIO bucket and return the file path.
        If `is_parse_path` is True, return the HTTP path instead of the S3 path.
        """
        try:
            self.client.put_object(
                Bucket=self.bucket_name,
                Key=filename,
                Body=audio_buffer.getvalue(),
                ContentType="audio/wav",
            )
            if self.is_parse_path:
                return f"{self.client.meta.endpoint_url}/{self.bucket_name}/{filename}"
            return f"s3://{self.bucket_name}/{filename}"
        except NoCredentialsError as e:
            raise Exception(f"Failed to upload audio to S3: {e}")


def generate_audio_to_buffer(args) -> BytesIO:
    """
    Run the `run_tts` function and capture the generated audio in a buffer.
    """
    # Temporarily modify `args.save_dir` to a local temp directory
    original_save_dir = args.save_dir
    temp_dir = "/tmp"
    args.save_dir = temp_dir

    # Run TTS inference
    run_tts(args)

    # Locate the output audio file in the temp directory
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    temp_file_path = os.path.join(temp_dir, f"{timestamp}.wav")

    # Load the audio into a buffer
    audio_buffer = BytesIO()
    with open(temp_file_path, "rb") as audio_file:
        audio_buffer.write(audio_file.read())
    audio_buffer.seek(0)

    # Clean up temporary file
    os.remove(temp_file_path)

    # Restore original save_dir
    args.save_dir = original_save_dir

    return audio_buffer


async def async_tts_handler(job: dict):
    """
    Handle TTS requests asynchronously.
    Extract parameters, run inference, and save the result to S3 or MinIO.
    """
    job_input = job.get("input")
    if not job_input or not job_input.get("text"):
        return {"error": "Missing required input: 'text'"}

    # Extract TTS input parameters
    text = job_input["text"]
    prompt_speech_path = job_input.get("prompt_speech_path")
    prompt_text = job_input.get("prompt_text")
    gender = job_input.get("gender")
    pitch = job_input.get("pitch")
    speed = job_input.get("speed")

    # Extract S3/MinIO parameters
    s3_endpoint = job_input.get("s3_endpoint")
    s3_clientid = job_input.get("s3_clientid")
    s3_secret = job_input.get("s3_secret")
    s3_bucket = job_input.get("s3_bucket")
    is_parse_path = job_input.get("is_parse_path", False)

    if not all([s3_endpoint, s3_clientid, s3_secret, s3_bucket]):
        return {"error": "Missing required S3 configuration parameters"}

    try:
        # Initialize CLI arguments for TTS
        args = parse_args()
        args.text = text
        args.prompt_text = prompt_text
        args.prompt_speech_path = prompt_speech_path
        args.gender = gender
        args.pitch = pitch
        args.speed = speed

        # Generate audio as buffer
        audio_buffer = generate_audio_to_buffer(args)

        # Initialize S3/MinIO uploader
        s3_uploader = S3Uploader(
            endpoint=s3_endpoint,
            access_key=s3_clientid,
            secret_key=s3_secret,
            bucket_name=s3_bucket,
            is_parse_path=is_parse_path,
        )

        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}.wav"

        # Upload audio to S3/MinIO
        s3_path = s3_uploader.upload_audio(filename, audio_buffer)

        return {"message": "Audio generated successfully", "s3_path": s3_path}
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    runpod.serverless.start({"handler": async_tts_handler})
