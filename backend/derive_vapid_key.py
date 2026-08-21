import base64

from cryptography.hazmat.primitives import serialization

with open("public_key.pem", "rb") as f:
    public_key = serialization.load_pem_public_key(f.read())

raw = public_key.public_bytes(
    encoding=serialization.Encoding.X962,
    format=serialization.PublicFormat.UncompressedPoint,
)

application_server_key = base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")
print(application_server_key)