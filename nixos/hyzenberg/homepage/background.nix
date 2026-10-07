# stuff for the background image rotation to keep the main file not bloated
{ xelib, ... }:
let
  url = "${xelib.apps.backgrounds.url}/current/1827398123";
in
{
  services.homepage-dashboard = {
    settings.background = {
      image = url;
      #  blur = "xs";
    };

    customJS = ''
      (function () {
        function inject() {
          const footer = document.getElementById("footer");
          if (!footer || document.getElementById("attribution")) return;
          const span = document.createElement("span");
          span.id = "attribution";
          footer.appendChild(span);
          fetch("${url}.json")
            .then(r => (r.ok ? r.json() : null))
            .then((img) => {
              if (!img || !img.author) return span.remove();
              span.appendChild(document.createTextNode("Photo by "));
              const a = document.createElement("a");
              a.href = img.pageUrl || img.source || "#";
              a.target = "_blank";
              a.rel = "noopener";
              a.textContent = img.author;
              span.appendChild(a);
              if (img.host) span.appendChild(document.createTextNode(" on " + img.host));
            })
            .catch(() => span.remove());
        }
        if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", inject);
        else inject();
      })();
    '';

    customCSS = ''
      #footer { position: relative; }
      #attribution {
        position: absolute;
        left: 2rem;
        bottom: 2rem;
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.75);
      }
      #attribution a { color: rgba(255, 255, 255, 0.9); text-decoration: underline; }
    '';
  };
}
