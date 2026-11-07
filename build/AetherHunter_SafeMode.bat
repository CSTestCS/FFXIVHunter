@echo off
rem Starts Aether Hunter with the OpenGL (compatibility) renderer.
rem Use this if the game shows a black screen or garbled graphics.
start "" "%~dp0AetherHunter.exe" --rendering-method gl_compatibility --rendering-driver opengl3
