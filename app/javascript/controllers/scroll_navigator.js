document.addEventListener("DOMContentLoaded", () => {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.remove("hidden-section");
        entry.target.classList.add("visible-section");

        if (entry.target.classList.contains("end-section")) {
          setTimeout(() => {
            window.location.href = "/";
          }, 1500);
        }
      }
    });
  }, {
    threshold: 0.5
  });

  document.querySelectorAll(".hidden-section").forEach(el => {
    observer.observe(el);
  });
});
