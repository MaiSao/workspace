for d in */; do
  [ -d "$d" ] || continue
  echo "Processing dir: ${d%/}"
  # xử lý ở đây
  kubectl config use-context ${d%/}
  cd ${d%/}
  echo "Start fluentbit ${d%/}" 
  bash start.sh
  cd ..
done
