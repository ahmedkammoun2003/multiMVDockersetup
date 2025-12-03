FROM python:3.9-slim

RUN useradd -m -u 1000 microservice
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

USER microservice
COPY --chown=microservice:microservice . .

EXPOSE 5002
CMD ["python", "app.py"]