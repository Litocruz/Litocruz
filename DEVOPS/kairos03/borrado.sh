# Este comando busca los PVs en estado 'Terminating' y les quita el freno de mano
for pv in $(oc get pv | grep Terminating | awk '{print $1}'); do
    echo "Forzando borrado de PV: $pv"
    oc patch pv $pv -p '{"metadata":{"finalizers":null}}' --type=merge
done
