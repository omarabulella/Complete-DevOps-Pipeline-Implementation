FROM  python:3.9-slim
RUN apt-get update \
    && pip install --upgrade pip \
    && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* 
WORKDIR /usr/src/app

COPY requirements.txt /usr/src/app/ 

COPY . .

RUN pip install --no-cache-dir -r requirements.txt
 
EXPOSE 8000

CMD ["python3", "hello.py"]

