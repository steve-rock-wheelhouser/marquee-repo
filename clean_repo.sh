#!/bin/bash

#cd /home/user/marquee-magic_repo
#rm aarch64/marquee-server-0.57.0-1.fc42.noarch.rpm
createrepo_c --update .
git add .
git commit -m "Remove broken marquee-server RPM"
git push
