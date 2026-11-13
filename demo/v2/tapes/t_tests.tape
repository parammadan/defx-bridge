Output raw/t_tests.mp4
Set Shell "bash"
Set FontSize 26
Set FontFamily "Menlo"
Set Width 1860
Set Height 840
Set Padding 30
Set Theme "Catppuccin Mocha"
Set TypingSpeed 15ms
Set Framerate 20
Hide
Type "cd ~/defx-bridge && export PS1='$ ' PS2='> ' && renice -n 15 -p $$ >/dev/null && clear"
Enter
Sleep 400ms
Show
Type `Rscript -e 'testthat::test_local(".")'`
Enter
Sleep 45s
