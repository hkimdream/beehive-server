#!/bin/sh
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

set -e

do_deploy() {

  set -o allexport
  source beehive.conf
  set +o allexport

  mkdir -p $BEEHIVE_ROOT/ssh_keys


  # copy default key only if no other exists
  if [ ! -e $BEEHIVE_ROOT/ssh_keys/${REGISTRATION_PUBKEY} ] ; then
    echo "Registration key missing: ${REGISTRATION_PUBKEY}"
    echo "running scripts/create_registration_key.sh ..."
    #cp ssh/beehive-registration-key.pub $BEEHIVE_ROOT/ssh_keys/
    scripts/create_registration_key.sh
  fi

  do_build

  do_deploy_only

  # Run setup only once
  if [  ! -e ${BEEHIVE_ROOT}/setup_success.flag ] ; then
    do_setup
    touch ${BEEHIVE_ROOT}/setup_success.flag
  fi


  sleep 3

  # this is not ideal...
  echo "updating nginx config..."
  cd ./beehive-nginx
  set -x
  ./update_nginx_config.sh
  set +x
  sleep 1
  
  until ./reload.sh
  do
    echo "nginx failed... retrying in 3 seconds"
    sleep 3
  done
  
  cd ..

}

do_setup() {
  for image in $(echo beehive-*); do
    # skip Makefile if target is missing anyway
    if ! grep --quiet '^setup:' $image/Makefile ; then
      continue
    fi
      
    echo "setup $image ..."
    cd $image
    make setup
    cd ..
    
  done
}


do_deploy_only() {
  
  for image in $(echo beehive-*); do
    echo "deploying $image ..."
    cd $image
    make deploy
    cd ..
  done

}


do_build() {

  for image in $(echo beehive-*); do
    echo "building $image ..."
    cd $image
    make build
    cd ..
  done

}


do_cleanup() {
  GLOBIGNORE=beehive-core
  set -x
  docker rm -f  beehive-*
  set +x
  unset GLOBIGNORE
}

if [ -z "$BEEHIVE_ROOT" ]; then
  echo "Environment variable BEEHIVE_ROOT is not defined, using ${PWD}/data/"
  export BEEHIVE_ROOT=${PWD}/data/
  sleep 1
fi


if [ -e "${BEEHIVE_ROOT}/.git" ]; then
  echo "Your BEEHIVE_ROOT folder (${BEEHIVE_ROOT}) seems to be a git repository. Please rename either BEEHIVE_ROOT or your git repository."
  exit 1
fi

if [ ! -e ./beehive.conf ] ;then
  echo "using beehive.conf.example"
  cp beehive.conf.example beehive.conf
fi



case $1 in
  deploy)
    do_deploy
    ;;
  setup)
    do_setup
    ;;
  cleanup)
    do_cleanup
    ;;
  test)
    python3 -m unittest discover -s tests
    ;;
  *)
    echo "Usage: do.sh (deploy|setup|cleanup|test)"
    exit 1
    ;;
esac
