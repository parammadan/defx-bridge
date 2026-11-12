Output demo/work/s08_raw.mp4
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
Type "# the generated workbook, read back from the .xlsx file with readxl"
Enter
Sleep 0.6s
Type `scripts/show_sheet.R artifacts/define_like_filled.xlsx Methods --cols ID,Type,Description,"Expression Code" --max 6`
Enter
Sleep 3.0s
Type "scripts/show_sheet.R artifacts/define_like_filled.xlsx PreserveMe"
Enter
Sleep 9s
