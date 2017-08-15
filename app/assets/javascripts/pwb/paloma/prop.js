var PwbPropsController = Paloma.controller('Pwb/Props');

PwbPropsController.prototype.show = function() {
  // Below for properties slider
  // don't have something similar for main landing yet
  $(".carousel-inner .item").click(function() {
    var carouselStatus = $('#propCarousel').data('status');
    if (carouselStatus && carouselStatus === "paused") {
      $('#propCarousel').carousel('cycle');
      $('#propCarousel').data('status', "cycling");
    } else {
      $('#propCarousel').carousel('pause');
      $('#propCarousel').data('status', "paused");
    }
  });

  var currentItemForMap = this.params.property_details;
  // if (typeof google === "undefined") {
  //   var self = this;
  //   window.map_callback = function() {
  //     INMOAPP.showMap(currentItemForMap);
  //   };
  //   $.getScript('https://maps.googleapis.com/maps/api/js?key=AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw&v=3.exp&sensor=false&callback=map_callback&libraries=places');
  // } else {
  //   INMOAPP.showMap(currentItemForMap);
  // }
};
