FROM public.ecr.aws/docker/library/python:3.11-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
USER 65534:65534
EXPOSE 8080
CMD ["python", "app.py"]
