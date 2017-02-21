var PwbWelcomeController = Paloma.controller('Pwb/Welcome');

PwbWelcomeController.prototype.index = function() {
  $(".carousel-inner .item").click(function () {
    var carouselStatus = $('#homepageCarousel').data('status');
    if (carouselStatus && carouselStatus === "paused") {
      $('#homepageCarousel').carousel('cycle');
      $('#homepageCarousel').data('status', "cycling");    
    } else{
      $('#homepageCarousel').carousel('pause');
      $('#homepageCarousel').data('status', "paused");    
    }
  });
};
