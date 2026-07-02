for d in */; do
  [ -d "$d" ] || continue
  echo "Processing dir: ${d%/}"
  # xử lý ở đây
  kubectl config use-context ${d%/}
  cd ${d%/}
  echo "Stop fluentbit ${d%/}" 
  bash stop.sh
  cd ..
done
