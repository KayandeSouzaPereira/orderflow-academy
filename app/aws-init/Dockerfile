# One-shot container that creates the AWS resources in Floci and seeds them.
# The script is baked into the image (no bind mount), which is more reliable on
# Docker Desktop and in CI.
FROM amazon/aws-cli:2.31.0
COPY init.sh /aws-init/init.sh
COPY seed/ /aws-init/seed/
ENTRYPOINT ["bash", "/aws-init/init.sh"]
