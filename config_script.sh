#!/bin/bash

# author: Piotr Michna
# e-mail: pm@piotrmichna.pl

RED="\e[0;31m"
GREEN="\e[0;32m"
BLUE="\e[0;34m"
GREY="\e[0;90m"
BLINK="\e[5m"
BOLD="\e[1m"
NC="\e[0m"
currentDate=$(date +"%F")
currentTime=$(date +"%T")

LOG_FILE="app.log"


function message(){
  if [ -n "$2" ] ; then
    case "$2" in
      '-t') # title
        echo -ne "\n\r${BLUE}${BOLD}------> $1 <-----------[ ${currentDate} ${currentTime} ]${NC}\n\r"
        echo "" |& tee -a $LOG_FILE &> /dev/null
        echo "------> $1 <-----------[ ${currentDate} ${currentTime} ]" |& tee -a $LOG_FILE &> /dev/null
      ;;
      '-e') # error
        echo -ne "${RED}${BLINK}ERROR${NC}${RED}-> $1 <---${NC}\n\r"
        echo "------> $1 <---" |& tee -a $LOG_FILE &> /dev/null
      ;;
      '-c') # correct ✓
        echo -ne "${GREY}[${GREEN}✓${GREY}]--->${BLUE} $1 ${GREY}<---${NC}\n\r"
        echo "------> $1 <---" |& tee -a $LOG_FILE &> /dev/null
      ;;
      '-m') # message
        echo -ne "${GREEN}------> $1 ${GREEN}<---${NC}\n\r"
        echo "------> $1 <---" |& tee -a $LOG_FILE &> /dev/null
      ;;
      '-q') # question
        echo -ne "${GREY}------> ${BOLD}$1: ${GREEN}"
      ;;
    esac
  else
    echo -ne "${GREY}------> $1 <---${NC}\n\r"
    echo "------> $1 <---" |& tee -a $LOG_FILE &> /dev/null
  fi
}

function get_param(){
  if [ -n "$1" ] ; then
    PARAM=""
    while [ "" == "$PARAM" ] ; do
      message "$1" "-q"
      read PARAM
      if [ -n "$2" ] ; then
        if [ `echo $2 | grep $PARAM | wc -l` -eq 0 ] ; then
          PARAM=""
        fi
      fi
    done
  fi
}

function check_dir(){
  if [ -n "$1" ] ; then
    while true ; do
      message "$1" "-q"
      read PARAM
      if [ -d "$HOME/$PARAM" ] ; then
        message "Katalog [ $HOME/$PARAM ] już istnieje!" "-e"
      else
        break
      fi
    done
  fi
}

function get_git_clone_config(){
  if [ "$PROJ_DIR" == "" ] ; then
    PROJ_DIR="dxd"
  fi

  mkdir /tmp/$PROJ_DIR
  while true ; do
    get_param "Podaj adres repozytorium aplikacji [q-quit]"

    if [ "$PARAM" == "Q" ] || [ "$PARAM" == "q" ] ; then
      rm -rf /tmp/$PROJ_DIR
      C_CGIT=0
      break
    else
      git clone $PARAM /tmp/$PROJ_DIR &> /dev/null

      if [ $? -eq 0 ] ; then
        rm -rf /tmp/$PROJ_DIR
        GIT_LINK=$PARAM
        C_CGIT=1
        break
      else
        message "Błędny adres repozytorium!" "-e"
      fi
    fi
  done  
}

function get_django_conf(){  
  check_dir "Podaj katalog projektu ~/"
  PROJ_DIR=$PARAM

  get_param "Załadować aplikacje z Githuba? [n/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    get_git_clone_config
  else
    C_CGIT=0
    get_param "Podaj katalog projektu Django: ~/$PROJ_DIR/"
    DJANGO_DIR=$PARAM
  fi
}

function get_conf_service(){
  get_param "Utworzyć usługę systemową dla aplikacji? gunicor + nginx [n/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    get_param "Podaj nazwa usługi systemowej (bez spacji)"
    C_SYS_NAME=$PARAM

    get_param "Podaj opis usługi systemowej"
    C_SYS_DESCRIPTION=$PARAM

    get_param "Podaj liste hostów: host0,host1.."
    C_SYS_HOSTS=$PARAM

    # host=$(echo $C_SYS_HOSTS | tr "," "\n")
    # local hosts=""
    # for addr in $host ; do
    #     echo "$addr"
    #     if [ "$hosts" == "" ] ; then
    #       hosts="'$addr'"
    #     else
    #       hosts="${hosts},'$addr'"
    #     fi
    # done
    # echo "django hosts =$hosts"

    C_SERVICE=1
  else
    C_SERVICE=0
  fi
}

function get_config_psql_db(){
  while true ; do
    get_param "Podaj nazwę bazy"
    PSQL_NAME=$PARAM
    x=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PSQL_NAME'"`
    if [ "$x" == "" ] ; then
      break
    else
      message "Baza danych już istnieje" "-e"
    fi
  done
}

function get_config_psql_user(){
  while true ; do
    if [ "$PSQL_USER" == "" ] ; then
      get_param "Podaj nazwę użytkownika bazy"
      PSQL_USER=$PARAM
    else
      message "Jeśli nie znasz hasła dla użytkonika $PSQL_USER konfiguracja nie będzie poprawna!" "-m"
      get_param "Czy użyć użytkownika [t/n]" "TtNn"
      if [ "$PARAM" == "N" ] || [ "$PARAM" == "n" ] ; then
        get_param "Podaj nazwę użytkownika bazy danych"
        PSQL_USER=$PARAM
      else
        break
      fi
    fi

    x=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PSQL_USER'"`
    if [ "$x" == "" ] ; then      
      break
    else
      message "Użytkownik baza danych już istnieje" "-e"
    fi
  done
  while true ; do
    message "Podaj hasło" "-q"
    read -s PSQL_PASS
    echo -ne "\n\r"

    message "Podaj ponownie hasło" "-q"
    read -s PARAM
    echo -ne "\n\r"
    if [ "$PSQL_PASS" == "$PARAM" ] ; then
      break
    else
      message "Hasła nie są zgodne" "-e"
    fi
  done

  get_param "Zapisać wszystkie hasła w pliku log? [n/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    C_PASS_LOG=1 
  else
    C_PASS_LOG=0
  fi
}

function get_config_psql(){
  get_param "Utworzyć konfiguracje bazy postgresql? [n/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    C_PSQL=1
    get_config_psql_db
    
  else
    C_PSQL=0
  fi
}

function get_config_user(){
  message "KONFIGURACJA DJANGO" "-m"
  get_django_conf

  message "KONFIGURACJA USŁUGI SYSTEMOWEJ" "-m"
  get_conf_service

}

function get_config_root(){
  get_param "Utworzyć użytkownika systemowego? [*/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    C_USER=1
  else
    C_USER=0
  fi
}

function get_config(){
  message "Konfiguracja instalatora" "-m"
  get_param "Modyfikacja prompt'a termianal? [*/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    C_PROMPT=1
  else
    C_PROMPT=0
  fi

  get_param "Instalacja i konfiguracja narzędzi? [*/t]" "TtNn"
  if [ "$PARAM" == "T" ] || [ "$PARAM" == "t" ] ; then
    C_TOOLS=1
  else
    C_TOOLS=0
  fi

  if [ "$USER" == "root" ] ; then
    get_config_root
  else
    get_config_user
  fi
}

#get_config
get_config_psql