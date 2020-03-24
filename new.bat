@echo off
echo author itning
SET NOW_TIME=%date:~0,4%-%date:~5,2%-%date:~8,2%-
SET FILE_NAME=%NOW_TIME%%1.md
hugo new post/%FILE_NAME%
