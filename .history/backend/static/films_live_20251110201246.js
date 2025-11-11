cd ~/Scrivania/drf_hugo_vue/backend
mkdir -p static/admin

cat > static/admin/films_live.js <<'EOF'
console.log('[films_live.js] caricato!');
/* demo minimale: quando torni sulla tab Admin, ricarica la lista */
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    setTimeout(() => location.reload(), 300);
  }
});
EOF
