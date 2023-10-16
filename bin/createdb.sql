CREATE DATABASE IF NOT EXISTS `@db` COLLATE '@col';
GRANT ALL ON `@db`.* TO '@user'@'%';
