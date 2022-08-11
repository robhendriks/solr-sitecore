#!/bin/bash

solrVersion=${1:-8.4.0}
detectorVersion=${2:-latest}
log4jVersion=${3:-2.17.0}

echo "solrVersion = $solrVersion"
echo "detectorVersion = $detectorVersion"
echo "log4jVersion = $log4jVersion"

echo "scanning for log4j jars"
find / -iname "*log4j-core*.jar"
mkdir -p /tmp/log4jscanner
cd /tmp/log4jscanner
wget "https://github.com/mergebase/log4j-detector/raw/master/log4j-detector-${detectorVersion}.jar"
echo "report for vulnerable files before workaround"
java -jar /tmp/log4jscanner/log4j-detector-${detectorVersion}.jar /

mkdir -p /tmp/log4j/${log4jVersion}
cd /tmp/log4j/${log4jVersion}
wget "https://dlcdn.apache.org/logging/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin.tar.gz"
tar -xf apache-log4j-${log4jVersion}-bin.tar.gz

rm -f /opt/dist/solr-${solrVersion}/server/lib/ext/log4j-api-*.jar
rm -f /opt/dist/solr-${solrVersion}/server/lib/ext/log4j-web-*.jar
rm -f /opt/dist/solr-${solrVersion}/server/lib/ext/log4j-core-*.jar
rm -f /opt/dist/solr-${solrVersion}/server/lib/ext/log4j-1.2-api-*.jar
rm -f /opt/dist/solr-${solrVersion}/server/lib/ext/log4j-slf4j-impl-*.jar
rm -f /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/log4j-api-*.jar
rm -f /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/log4j-web-*.jar
rm -f /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/log4j-core-*.jar

cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-api-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/server/lib/ext/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-web-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/server/lib/ext/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-core-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/server/lib/ext/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-1.2-api-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/server/lib/ext/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-slf4j-impl-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/server/lib/ext/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-api-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-web-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/
cp /tmp/log4j/${log4jVersion}/apache-log4j-${log4jVersion}-bin/log4j-core-${log4jVersion}.jar /opt/dist/solr-${solrVersion}/contrib/prometheus-exporter/lib/

service solr restart

echo "report for vulnerable files after workaround"
java -jar /tmp/log4jscanner/log4j-detector-${detectorVersion}.jar /
