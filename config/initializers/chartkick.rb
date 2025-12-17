# frozen_string_literal: true

# Chartkick configuration for analytics dashboards
# Uses Chart.js as the default charting library

Chartkick.options = {
  # Default chart height
  height: "300px",

  # Chart.js specific options
  library: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: "bottom"
      }
    }
  }
}
