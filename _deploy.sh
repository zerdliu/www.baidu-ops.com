#!/bin/bash
function data_upload_ftp() {

  ftp -inv 174.120.207.225 << EOF

  user baiduops 3bEL17i3ft

  cd public_html

  mput _site

  close

  bye

EOF

}

function data_upload_lftp() {
  HOST="174.120.207.225"
  USER="baiduops"
  PASS="3bEL17i3ft"
  LCD="_site"
  RCD="public_html/"
  lftp -c "
  set ssl:verify-certificate no
  set ftp:list-options -a;
  open ftp://$USER:$PASS@$HOST; 
  lcd $LCD;
  cd $RCD;
  mirror --reverse \
         --delete \
         --verbose \
         --exclude-glob a-dir-to-exclude/ \
         --exclude-glob a-file-to-exclude \
         --exclude-glob a-file-group-to-exclude* \
         --exclude-glob other-files-to-esclude"
}

data_upload_lftp
