# tests/test_validator.py
def test_validate_email():
    assert validate_email("test@example.com") == True
    assert validate_email("invalid") == False