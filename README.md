# sh2doc

This script runs though all directories specified in the field `@DIRS` and looks at all files whether 
they contain special documentation makers like:

- `##BRIEF`
- `##AUTHOR`
- `##DETAILS`
- `##DATE`
- `##CHANGELOG`

If any of these are found, the file is added to an overview contained in an index.html 
file which lists file name (and a link to a detailed description). Furthermore another 
HTML file is created which contains detailed information of the file given in the 
documentation. Additional meta data of the file such as last changed could be added.
A line that starts with spaces only and contains a comment starting with '#+#' will be added to the details.

Empty lines or "##" denote that the subsection (e.g. DETAILS) is finished. So use minimal 
HTML for paragraph formatting and line breaks.

