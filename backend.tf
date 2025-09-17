terraform {
  backend "remote" {
    organization = "StudyTestKakazu"

    workspaces {
      name = "airflowInfra"
    }
  }
}
