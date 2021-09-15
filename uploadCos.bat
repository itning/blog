@echo off
hugo --minify
cd public
coscmd upload -r ./ ./
