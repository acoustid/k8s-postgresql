FROM postgres:11.2 as builder

RUN apt-get update && \
    apt-get install -y \
        python \
        python-pip \
        python-virtualenv \
        libpq-dev \
        git \
        postgresql-server-dev-all

RUN virtualenv /opt/patroni
RUN /opt/patroni/bin/pip install requests psycopg2
RUN /opt/patroni/bin/pip install patroni[etcd]

RUN git clone https://github.com/acoustid/pg_acoustid.git /opt/pg_acoustid && \
    cd /opt/pg_acoustid && \
    make && \
    make install

FROM postgres:11.2

RUN apt-get update && \
    apt-get install -y \
        python \
        postgresql-$PG_MAJOR-slony1-2 \
        slony1-2-bin \
        dumb-init
        curl

COPY setup_db.sh /docker-entrypoint-initdb.d/setup_db.sh

COPY --from=builder /opt/patroni/ /opt/patroni/
COPY --from=builder /usr/lib/postgresql/$PG_MAJOR/lib/acoustid.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=builder /usr/share/postgresql/$PG_MAJOR/extension/acoustid* /usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=builder /usr/lib/postgresql/$PG_MAJOR/lib/bitcode/acoustid /usr/lib/postgresql/$PG_MAJOR/lib/bitcode/

RUN cd /usr/local/bin && \
    curl -LO https://github.com/wal-g/wal-g/releases/download/v0.2.9/wal-g.linux-amd64.tar.gz && \
    tar xvf wal-g.linux-amd64.tar.gz && \
    rm wal-g.linux-amd64.tar.gz && \
    ln -s /opt/patroni/bin/patroni /usr/local/bin && \
    ln -s /opt/patroni/bin/patronictl /usr/local/bin && \
    ln -s /opt/patroni/bin/patroni_wale_restore /usr/local/bin
