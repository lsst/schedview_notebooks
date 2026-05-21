# schedview_notebooks
Notebooks associated with schedview, sometimes for execution by Times Square

Additional information on running the notebooks can be found in the "reports" section of the documentation for `schedview` itself.


## Development

This repository uses Pre-commit to keep notebooks formatted and clean. Install Pre-commit by running:

```bash
pip install pre-commit
pre-commit install
```

## Style and templates

The "templates" directory holds files used by nbconvert in generation of html from jupyter notebooks.
It places a declaration of css style elements
(copied from documenteer so it looks like other Rubin Observatory pages)
into the header,
but otherwise leaves the style as the default "lab" html export style provided by nbconvert.
(nbconvert uses jinja2 templates.)
