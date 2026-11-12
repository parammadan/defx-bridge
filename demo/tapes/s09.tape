Output demo/work/s09_raw.mp4
Set Shell "bash"
Set FontSize 22
Set FontFamily "Menlo"
Set Width 1920
Set Height 950
Set Padding 36
Set Theme "Catppuccin Mocha"
Set TypingSpeed 15ms
Set Framerate 20
Hide
Type "export PS1='$ ' PS2='> ' && renice -n 15 -p $$ >/dev/null && clear"
Enter
Sleep 300ms
Show
Type "# Variables before (template) and after (generated workbook)"
Enter
Sleep 0.6s
Type "scripts/show_sheet.R examples/define_like_template.xlsx Variables --where Variable=AERELFL --cols Dataset,Variable,Origin,Method"
Enter
Sleep 3.0s
Type `scripts/show_sheet.R artifacts/define_like_filled.xlsx Variables --where Dataset=ADAE --cols Variable,Origin,Method,"Developer Notes"`
Enter
Sleep 9s
