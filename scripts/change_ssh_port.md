1. Launch and connect to EC2 instance running Amazon Linux 2.

2. Promote to root and edit /etc/ssh/sshd_config
`sudo vi /etc/ssh/sshd_config`

3. Edit line 17 (usually 17) #PORT 22. You'll need to un-comment the line and change the port to whatever you like.
`PORT XYZ`

4. Save changes and exit
`:wq`

5. Restart sshd
For Amazon Linux, RHEL 5, and SUSE Linux, use this command:
`sudo service sshd restart`
For Ubuntu, use this command:
`sudo service ssh restart`
