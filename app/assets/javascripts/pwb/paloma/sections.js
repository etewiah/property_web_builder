var PwbSectionsController = Paloma.controller('Pwb/Sections');

PwbSectionsController.prototype.contact_us = function() {

  var currentItemForMap = this.params.current_agency_primary_address;
  // http://stackoverflow.com/questions/2647867/how-to-determine-if-variable-is-undefined-or-null
  // if (currentItemForMap == null) {
  if (!this.params.show_contact_map) {
    return;
  }
  if (typeof google === "undefined") {
    var self = this;
    window.map_callback = function() {
      INMOAPP.showMap(currentItemForMap);
    };
    $.getScript('https://maps.googleapis.com/maps/api/js?key=AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw&v=3.exp&sensor=false&callback=map_callback&libraries=places');
  } else {
    INMOAPP.showMap(currentItemForMap);
  }
};


var PwbPropsController = Paloma.controller('Pwb/Props');

PwbPropsController.prototype.show = function() {
  // Below for properties slider
  // don't have something similar for main landing yet
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

  var currentItemForMap = this.params.property_details;
  if (typeof google === "undefined") {
    var self = this;
    window.map_callback = function() {
      INMOAPP.showMap(currentItemForMap);
    };
    $.getScript('https://maps.googleapis.com/maps/api/js?key=AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw&v=3.exp&sensor=false&callback=map_callback&libraries=places');
  } else {
    INMOAPP.showMap(currentItemForMap);
  }
};
