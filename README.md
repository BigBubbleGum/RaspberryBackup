# RaspberryBackup
在Linux系统中一键备份树莓派系统SD卡的脚本

脚本文件来源：https://blog.csdn.net/qingtian11112/article/details/99825257

使用方法：
step1：下载脚本文件rpi-backup.sh到Linux系统中
step2：把需要备份的SD卡插入Linux系统中，用 df -h 命令查询下 SD 卡对应的设备名。
step3：进入脚本文件 rpi-backup.sh 所在目录，只需要下面两行命令即可完成 SD 卡备份，最终 img 文件会生成在`~/backupimg/`文件夹下。
       sudo chmod +x rpi-backup.sh            #需要赋可执行权限
       /rpi-backup.sh /dev/sdb1 /dev/sdb2     #脚本执行有两个参数，第一个参数是树莓派SD卡`/boot`分区的设备名：/dev/sdb1，第二个参 
                                               数是`/`分区的设备名：/dev/sdb2，视情况修改）
