# Firebot: A Continuous Integration Tool for FDS

Firebot is a script that can be run at regular intervals as part of a continuous integration program. At NIST, this script is run by a user named `firebot` on a linux cluster each night. The user `firebot` clones the various repositories in the GitHub project named `firemodels`, builds FDS and Smokeview, runs the verification cases, checks the results for accuracy, and builds all of the manuals. The entire process takes a few hours to complete.

Any developer can also run Firebot to test branches or new features. Instructions are below.

## Set-Up

The following steps need only be done once. The exact phrasing of the commands might different with different flavors of linux.

1. Clone the `bot` repository included in the GitHub organization named `firemodels`.  Other repositories needed by fdsbot include `fds`, `smv`, `out`, `exp`, `fig`, and `cad`. If these are not already cloned, they will be by fdsbot. If you are running `fdsbot` yourself in your own space, clone and update these repositories yourself. 

2. Ensure that the following software packages are installed on the system:

    * Intel Fortran and C compilers, Intel MPI
    * LaTeX (TeX Live distribution), be sure to make this the default LaTeX in the system-wide PATH
    * Python
    * Slurm

3. Firebot uses email notifications for build status updates. Ensure that outbound emails can be sent using the `mail` command.

4. Install libraries for Smokeview. On CentOS, you can use the following command:
   ```
   yum install mesa-libGL-devel mesa-libGLU-devel libXmu-devel libXi-devel xorg-x11-server-Xvfb
   ```

5. Ensure that the Intel compilers have been properly initialized. You can test this by typing `ifx --version` at the command prompt.

6. Setup passwordless SSH for the your account. Generate SSH keys and ensure that the head node can SSH into all of the compute nodes. Also, make sure that your account information is propagated across all compute nodes.

7. Ensure that the Slurm queuing system is working.

8. By default, fdsbot sends email to the email address configured for your bot repo (output of command `git config user.email` ) .  If you wish email to go to different email addresses, create a file named $HOME/.fdsbot/firebot_email_list.sh for some `user1` and `user2` (or more) that looks like:

   ```
   #!/bin/bash
   mailToFDS="user1@host1.com, user2@host2.com"
   ```

## Running fdsbot

The script `fdsbot.sh` is run using the wrapper script `run_fdsbot.sh`. This script uses a locking file that ensures multiple instances of fdsbot do not run at the same time, which would cause file conflicts. To see the various options associated with running fdsbot, type
```
./run_fdsbot.sh -h
```
To run `fdsbot` to test local changes in your own space 
```
nohup ./run_fdsbot.sh -m user@host.com &
```
This will run fdsbot without updating your repos or cleaning/erasing files. Use `-q <partition>` to specify a particular queue. 

Each night, the user named firebot runs the fdsbot script using the command:
```
bash -lc "./run_fdsbot.sh -y -q firebot -R nightly  -U -W /opt/www/html -w fdsbot/clone  > $HOME/.fdsbot/fdsbot_test1.out"
```
The `-y` option causes fdsbot to run without pausing, `-q` specifies the Slurm queue to run cases in, `-R nightly` renames branches that are cloned to nightly. The other options, `-U`, `-W` and `-w` are used to upload results to a web site and to Github. 

To kill fdsbot, cd to the directory containing fdsbot.sh and type:
```
./run_fdsbot.sh -k
```
You can run fdsbot regularly using a `crontab` file by adding an entry like the following using the `crontab -e` command:
```
PATH=/bin:/usr/bin:/usr/local/bin:/home/<username>/firemodels/bot/Firebot:$PATH
MAILTO=""
# Run fdsbot at 11:32 PM every night
56 21 * * * cd ~/<username>/firemodels/bot/Fdsbot ; bash -lc "./run_fdsbot.sh <options>"
```
The output from fdsbot is written into the directory called `output` which is in the same directory as the `fdsbot.sh` script itself. When fdsbot completes, email should be sent to the specified list of addresses. The `fds/Manuals` directory in the `fds` repository containing manuals and figures is copied to the directdory `$HOME/.fdsbot/Manuals`.

## Updating Timing

Fdsbot compares timings for cases it runs with a corresponding set of base timings located in the fig repo at `fig/fds/Reference_Times/base_times.csv` .
To update the base timings on a Linux or Mac computer:

Assume bot, fig and fds repos etc are under `$HOME/FireModels_fork`

1.  bring fig repo up to date
```
    cd $HOME/FireModels_fork/fig
    git remote update
    git merge firemodels/master
    git merge origin/master
    git push origin master
```
2. add updated timings to the fig repo

Each time fdsbot runs it outputs a timing spreadsheet file (file with .csv extention) to
`$HOME/.fdsbot/history` where `$HOME` is home directory of the account that ran fdsbot. 
The timing file will have a name like `FDS6.7.9-1277-g43cd84dc2_timing.csv` .
To update the reference timing file in the fig repo:

   *  Copy the desired timing.csv file from .fdsbot/history (usually the latest) to the `fig/fds/Reference_Times` directory and
rename the file base_times.csv
   * cd into the `fds` repo where `fdsbot` was run and type `git describe --dirty --local` .  Copy the output of this 
   command to `fig/fds/Reference_Times/FDS_REVISION`

`FDS_REVISION` is also copied into the fig repo so we know what version of fds produced the base reference times.




 


