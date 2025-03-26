import pytest
from handler import async_tts_handler


@pytest.mark.asyncio
async def test_async_tts_handler_success():
    test_job = {
        "input": {
            "text": "Testing TTS output to S3.",
            "s3_endpoint": "http://localhost:9000",
            "s3_clientid": "minioadmin",
            "s3_secret": "minioadmin",
            "s3_bucket": "tts-outputs",
            "is_parse_path": True,
            "gender": "female",
            "pitch": "low",
            "speed": "moderate",
        }
    }
    result = await async_tts_handler(test_job)
    assert "error" not in result
    assert "s3_path" in result


@pytest.mark.asyncio
async def test_async_tts_handler_missing_text():
    test_job = {
        "input": {
            "s3_endpoint": "http://localhost:9000",
            "s3_clientid": "minioadmin",
            "s3_secret": "minioadmin",
            "s3_bucket": "tts-outputs",
        }
    }
    result = await async_tts_handler(test_job)
    assert "error" in result
    assert result["error"] == "Missing required input: 'text'"
