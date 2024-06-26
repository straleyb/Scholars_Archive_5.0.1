#!/bin/sh

pid_dir="/data/tmp/pids"

timestamp=`date +'%Y-%m-%d %H:%M:%S'`
echo "[$timestamp] Building ScholarsArchive (${RAILS_ENV})"
echo "   RAILS_ENV:                   $RAILS_ENV"
echo "   SCHOLARSARCHIVE_DB_HOST:     $SCHOLARSARCHIVE_DB_HOST"
echo "   SCHOLARSARCHIVE_FEDORA_URL:  $SCHOLARSARCHIVE_FEDORA_URL"
echo "   SCHOLARSARCHIVE_SOLR_URL:    $SCHOLARSARCHIVE_SOLR_URL"
echo "   SCHOLARSARCHIVE_TRIPLESTORE: $SCHOLARSARCHIVE_TRIPLESTORE_ADAPTER_URL"
echo ""

if [ ! -d "$pid_dir" ]; then
   mkdir -p "$pid_dir"
fi

rm -f $pid_dir/puma.pid
./build/install_gems.sh

chown postgres ./pg_hba.conf
cp ./pg_hba.conf /etc/postgresql/13/main/
su - postgres && pg_ctlcluster 13 main start
psql -U postgres -c "CREATE ROLE root with LOGIN"
psql -U postgres -c "CREATE DATABASE scholars_archive_development"
psql -U postgres -c "ALTER ROLE root with SUPERUSER"
su - root

# Do not auto-migrate for production environment
if [ "${RAILS_ENV}" != 'production' ]; then
  ./build/validate_migrated.sh
fi

# Submit a marker to honeycomb marking the time the application starts booting
if [ "${RAILS_ENV}" == 'production' -o "${RAILS_ENV}" == 'staging' ]; then
  echo "Creating Honeycomb deployment marker in $HONEYCOMB_DATASET"
  curl -sL https://api.honeycomb.io/1/markers/$HONEYCOMB_DATASET -X POST -H "X-Honeycomb-Team: ${HONEYCOMB_WRITEKEY}" -d "{\"message\":\"${RAILS_ENV} - ${DEPLOYED_VERSION} - Rails booting\", \"type\":\"deploy\"}"
fi

# Precompile assets
if [ "${RAILS_ENV}" == 'production' -o "${RAILS_ENV}" == 'staging' ]; then
   timestamp=`date +'%Y-%m-%d %H:%M:%S'`
   echo "[$timestamp] Precompiling assets ($RAILS_ENV)"
   RAILS_ENV=$RAILS_ENV SECRET_KEY_BASE=temporary bundle exec rails assets:precompile
fi

# Start Puma
timestamp=`date +'%Y-%m-%d %H:%M:%S'`
echo "[$timestamp] Starting puma ($RAILS_ENV)"
RAILS_ENV=$RAILS_ENV bundle exec puma -e ${RAILS_ENV} \
 --dir /data --pidfile $pid_dir/puma.pid -b tcp://0.0.0.0:3000

# Fall through in case puma dies
if [ "$RAILS_ENV" != "production" ]; then
   timestamp=`date +'%Y-%m-%d %H:%M:%S'`
   echo "[$timestamp] Fell through puma, starting life support systems."

   while `true`; do
      timestamp=`date +'%Y-%m-%d %H:%M:%S'`
      echo "[$timestamp] sleeping..."
      sleep 30
   done
fi


