FROM python:3.11.6

# Install Node.js (npx comes bundled with npm)
RUN apt-get update && apt-get install -y curl \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV SOLC_VERSION=0.8.19

# Set working directory
WORKDIR /app

# Install Slither and required solc version
RUN echo "slither-analyzer==0.10.4" > requirements.txt
RUN pip install -r requirements.txt
RUN solc-select install 0.8.19
RUN solc-select use 0.8.19

RUN useradd -m -s /bin/bash slither
USER slither

# Run the slither analysis scripts
CMD ["/app/scripts/slither.sh"]
