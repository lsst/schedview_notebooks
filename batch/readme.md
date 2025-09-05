The conda environment provided in the jupyter aspect of the USDF RSP,
and therefore alse Time Square, differs somewhat from the "lsst" environment
available on the development nodes.

To get these batch scripts to execute as they would on a jupyter aspect
notebook or on Times Square, the conda environment there needs to be
duplicated somewhere it can be activated from the slurm job.

Begin by starting a USDF notebook-aspect jupyter lab, making careful note
of which image you select.

From within that jupyterlab, start a terminal, and record the contents
of the environment provided. In the example used below, this was w2025_36,
and the `schedview_notebooks` repository was checked-out into
`/sdf/data/rubin/user/neilsen/devel/schedview_notebooks` .

So, recording the conda environment we want to replicate:

```
setup lsst_sitcom
cd /sdf/data/rubin/user/neilsen/devel/schedview_notebooks/batch
conda list --explicit > like_rsp_w2025_36_spec.txt
```

Then log into a USDF development node, go to the directory where
you saved the spec file above, and create an environment in the
shared scheduler space:

```
cd /sdf/data/rubin/user/neilsen/devel/schedview_notebooks/batch
source /sdf/group/rubin/sw/w_latest/loadLSST.sh
conda create --prefix /sdf/data/rubin/shared/scheduler/envs/like_rsp_w2025_36 --file  like_rsp_w2025_36_spec.txt
```

Finally, update the bash scripts that need it (batch/prenight.sh and batch/scheduler_nightsum.sh),
for example:

```
source /sdf/group/rubin/sw/w_latest/loadLSST.sh
conda activate /sdf/data/rubin/shared/scheduler/envs/like_rsp_w2025_36
```

Even though we aren't using the environment provided by the source of `loadLSST.sh` above,
it's still needed to get `conda` into our path.