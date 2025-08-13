(function () {
    // apiBase preso da hugo.yaml → params.apiBase
    const API = (window.DJUNGO && window.DJUNGO.API_BASE) || "{{ .Site.Params.apiBase }}";
    
    // NB: la riga sopra verrà resa correttamente SOLO se questo JS passa da tpl Hugo.
    // Con PaperMod/customJS passa da Hugo Pipes, quindi ok.
  
    function mountApp() {
      var el = document.getElementById('film-app');
      if (!el || !window.Vue) return;
  
      new Vue({
        el: '#film-app',
        data: {
          films: [],
          loading: false,
          error: '',
          newFilm: { title: '', link: '', description: '', image: '' }
        },
        created() { this.fetchFilms(); },
        methods: {
          async fetchFilms() {
            this.error = '';
            try {
              const res = await fetch(`${API}/films/`);
              if (!res.ok) throw new Error(`GET failed: ${res.status}`);
              this.films = await res.json();
            } catch (e) { this.error = e.message; }
          },
          async addFilm() {
            this.loading = true; this.error = '';
            try {
              const res = await fetch(`${API}/films/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.newFilm)
              });
              if (!res.ok) {
                const body = await res.text();
                throw new Error(`POST failed: ${res.status} ${body}`);
              }
              const film = await res.json();
              this.films.unshift(film);
              this.newFilm = { title: '', link: '', description: '', image: '' };
            } catch (e) { this.error = e.message; }
            finally { this.loading = false; }
          }
        }
      });
    }
  
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', mountApp);
    } else {
      mountApp();
    }
  })();
  