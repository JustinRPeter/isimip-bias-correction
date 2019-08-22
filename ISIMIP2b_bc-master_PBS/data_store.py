class Vars:
    def __init__(self, name, enabled, obs_dir, gcm_dir,
                rcp, version, projection_rcp, projection_version):
        self.name = name
        self.enabled = enabled
        self.obs_dir = obs_dir
        self.obs_file = (obs_dir.split('/')[-1])
        self.gcm_dir = gcm_dir
        self.rcp = rcp
        self.version = version
        self.projection_rcp = projection_rcp
        self.projection_version = projection_version