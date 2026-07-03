# Dataset and reference-data helpers.

# checks for some specified gene identifier in several different reference annotations
# and mapping
function check_gene {
  local query=$1

  # Strip "LOC" prefix, if present;
  # "LOC" genes are listed in NCBI genes without the "LOC" prefix
  # https://www.ncbi.nlm.nih.gov/books/NBK3840/
  if [[ "$query" != "${query#LOC}" ]]; then
    echo "Removing LOC prefix..."
    query=${query#LOC}
  fi

  echo "Checking Ensembl GRCh37 GTF..."
  zgrep "$query" /data/ref/human/ensembl/GRCh37/100/Homo_sapiens.GRCh37.87.gtf.gz

  echo "Checking Ensembl GRCh38 GTF..."
  zgrep "$query" /data/ref/human/ensembl/GRCh38/100/Homo_sapiens.GRCh38.100.gtf.gz

  echo "Checking HUGO gene symbol mapping..."
  grep "$query" /data/ref/human/hugo/genenames_2020-08-08.tsv

  echo "Checking NCBI Genes..."
  zgrep "$query" /data/ref/human/ncbi/Homo_sapiens.gene_info.gz
}

# preview table
# csvpeek in.csv [num rows]
function csvpeek {
  local numrows="${2:-3}"

  if [[ $1 == *.(tsv|txt)* ]]; then
    csvlook \
      -d $'\t' \
      --max-rows "$numrows" \
      --max-column-width 20 \
      "$1"
  elif [[ $1 == *.csv* ]]; then
    csvlook \
      --max-rows "$numrows" \
      --max-column-width 20 \
      "$1"
  else
    echo "Unrecognized file extension!"
  fi
}

# number of columns
function ncol {
  if [[ $1 == *.tsv* ]]; then
    csvgrep -n -t "$1" | wc -l
  elif [[ $1 == *.csv* ]]; then
    csvgrep -n "$1" | wc -l
  elif [[ $1 == *.feather ]]; then
    python -c \
      "import sys; import pandas as pd; print(pd.read_feather(sys.argv[1]).shape[1])" "$1"
  else
    echo "Unsupported format..."
  fi
}

# opens a specified dataset in ipython
function o {
  local filename ext

  # get extension, excluding .gz
  filename=${1/.gz/}
  ext="${filename##*.}"

  if [[ "$ext" == "feather" ]]; then
    ipython -i -c "import pandas as pd; df=pd.read_feather('$1'); df;"
  elif [[ "$ext" == "parquet" ]]; then
    ipython -i -c "import pandas as pd; df=pd.read_parquet('$1'); df;"
  elif [[ "$ext" == "csv" ]]; then
    ipython -i -c "import pandas as pd; df=pd.read_csv('$1'); df;"
  elif [[ "$ext" == "tsv" || "$ext" == "txt" ]]; then
    ipython -i -c "import pandas as pd; df=pd.read_csv('$1', sep='\t'); df;"
  else
    echo "Unrecognized filetype specified: $ext"
  fi
}

# helper function to quickly find and load a dataset from a set of known
# locations into ipython
function dat {
  local target
  local searchpaths=(/data/packages /data/proj /data/clean)

  target=$(fd . -e tsv -e feather -e parquet -e csv -e gz "${searchpaths[@]}" | fzf -1 --exact)

  if [[ -n "$target" ]]; then
    echo "Loading dataset $target..."
    o "$target"
  fi
}

# similar to dat, but limited to datapackages and including preview pane
function datp {
  # version=$(/bin/ls /data/packages | tail -n1)
  # searchpaths="/data/packages/$version"
  local target
  local searchpaths=(/data/packages)

  target=$(fd datapackage "${searchpaths[@]}" --exclude archive | fzf -1 --exact --preview 'nodes info {}')

  if [[ -n "$target" ]]; then
    echo "Loading $target..."

    ipython -i -c "from nodes.nodes import DataFrameNode; pkg=DataFrameNode.from_pkg('$target');"
  fi
}
